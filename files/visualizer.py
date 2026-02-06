"""
Visualizer - Creates annotated plate image and CSV report.
"""

import cv2
import csv
import numpy as np
from config import ROWS, COLS, ROW_LABELS, ANTIFUNGALS, CONCENTRATIONS


def create_annotated_image(plate_image: np.ndarray, classified_wells: dict, 
                           mic_results: list) -> np.ndarray:
    """
    Create an annotated version of the plate image with:
    - Well classification markers (green circle = growth, red = inhibition, yellow = partial)
    - MIC value indicators (white arrow/line at MIC column)
    - Growth score text overlay
    """
    annotated = plate_image.copy()
    h, w = annotated.shape[:2]
    cell_h = h / ROWS
    cell_w = w / COLS
    
    # Scale font based on image size
    font_scale = min(cell_w, cell_h) / 120.0
    font_scale = max(0.25, min(font_scale, 0.7))
    thickness = max(1, int(font_scale * 2))
    
    # Build MIC column lookup
    mic_columns = {}
    for r in mic_results:
        row_idx = ROW_LABELS.index(r['row'])
        mic_columns[row_idx] = r['mic_column']
    
    for (row, col), data in classified_wells.items():
        cx, cy = data['center']
        classification = data['classification']
        growth_score = data['growth_score']
        
        # Color coding
        if classification == 'growth':
            color = (0, 200, 0)       # Green = growth
            marker = 'G'
        elif classification == 'inhibition':
            color = (0, 0, 220)       # Red (BGR) = inhibition
            marker = 'I'
        else:
            color = (0, 200, 220)     # Yellow = partial
            marker = 'P'
        
        # Draw circle around well
        radius = int(min(cell_h, cell_w) * 0.35)
        cv2.circle(annotated, (cx, cy), radius, color, 2)
        
        # Draw score text
        score_text = f"{growth_score:.2f}"
        text_size = cv2.getTextSize(score_text, cv2.FONT_HERSHEY_SIMPLEX, font_scale * 0.8, thickness)[0]
        text_x = cx - text_size[0] // 2
        text_y = cy + text_size[1] // 2
        
        # Background rectangle for readability
        cv2.rectangle(annotated, 
                      (text_x - 2, text_y - text_size[1] - 2),
                      (text_x + text_size[0] + 2, text_y + 4),
                      (0, 0, 0), -1)
        cv2.putText(annotated, score_text, (text_x, text_y),
                    cv2.FONT_HERSHEY_SIMPLEX, font_scale * 0.8, (255, 255, 255), thickness)
        
        # Mark MIC well with a thick border
        if mic_columns.get(row) == col:
            cv2.circle(annotated, (cx, cy), radius + 4, (255, 255, 255), 3)
            cv2.circle(annotated, (cx, cy), radius + 4, (0, 255, 255), 2)
    
    # Add row/column labels
    annotated = add_labels(annotated, mic_results)
    
    return annotated


def add_labels(image: np.ndarray, mic_results: list) -> np.ndarray:
    """Add row and column labels, plus MIC values as a side panel."""
    h, w = image.shape[:2]
    
    # Create wider canvas with left panel for row labels and right panel for MIC values
    left_margin = int(w * 0.08)
    right_margin = int(w * 0.20)
    top_margin = int(h * 0.06)
    
    canvas_w = w + left_margin + right_margin
    canvas_h = h + top_margin
    canvas = np.ones((canvas_h, canvas_w, 3), dtype=np.uint8) * 255
    
    # Place plate image
    canvas[top_margin:top_margin + h, left_margin:left_margin + w] = image
    
    cell_h = h / ROWS
    cell_w = w / COLS
    
    font = cv2.FONT_HERSHEY_SIMPLEX
    font_scale = min(cell_w, cell_h) / 90.0
    font_scale = max(0.35, min(font_scale, 0.8))
    thickness = max(1, int(font_scale * 2))
    
    # Row labels (left side)
    for row_idx in range(ROWS):
        row_label = ROW_LABELS[row_idx]
        atm = ANTIFUNGALS[row_label]
        label = f"{row_label}-{atm}"
        
        cy = top_margin + int((row_idx + 0.5) * cell_h)
        text_size = cv2.getTextSize(label, font, font_scale, thickness)[0]
        tx = (left_margin - text_size[0]) // 2
        ty = cy + text_size[1] // 2
        cv2.putText(canvas, label, (max(2, tx), ty), font, font_scale, (0, 0, 0), thickness)
    
    # Column labels (top)
    for col_idx in range(COLS):
        label = str(col_idx + 1)
        cx = left_margin + int((col_idx + 0.5) * cell_w)
        text_size = cv2.getTextSize(label, font, font_scale, thickness)[0]
        tx = cx - text_size[0] // 2
        ty = top_margin - 5
        cv2.putText(canvas, label, (tx, max(15, ty)), font, font_scale, (0, 0, 0), thickness)
    
    # MIC values panel (right side)
    panel_x = left_margin + w + 10
    panel_y_start = top_margin + 5
    
    title = "MIC (mg/L)"
    cv2.putText(canvas, title, (panel_x, panel_y_start), font, font_scale * 1.0, (0, 0, 0), thickness + 1)
    
    for i, r in enumerate(mic_results):
        y = panel_y_start + int((i + 1) * cell_h * 0.9) + 10
        mic_str = str(r['mic_value']) if r['mic_value'] is not None else 'N/A'
        note = r['note']
        
        if note and not note.startswith('>') and not note.startswith('≤'):
            text = f"{r['antifungal']}: {mic_str}"
        elif note:
            text = f"{r['antifungal']}: {note}"
        else:
            text = f"{r['antifungal']}: {mic_str}"
        
        color = (0, 0, 180) if r['mic_value'] is not None else (100, 100, 100)
        cv2.putText(canvas, text, (panel_x, y), font, font_scale * 0.9, color, thickness)
    
    return canvas


def create_score_heatmap(classified_wells: dict) -> np.ndarray:
    """
    Create a separate heatmap image showing growth scores.
    Green = growth, Red = inhibition.
    """
    cell_size = 60
    margin = 80
    
    img_w = COLS * cell_size + margin
    img_h = ROWS * cell_size + margin
    heatmap = np.ones((img_h, img_w, 3), dtype=np.uint8) * 240
    
    font = cv2.FONT_HERSHEY_SIMPLEX
    
    # Column headers
    for col in range(COLS):
        cx = margin + col * cell_size + cell_size // 2
        label = str(col + 1)
        ts = cv2.getTextSize(label, font, 0.4, 1)[0]
        cv2.putText(heatmap, label, (cx - ts[0]//2, 20), font, 0.4, (0, 0, 0), 1)
    
    for row in range(ROWS):
        # Row label
        row_label = ROW_LABELS[row]
        atm = ANTIFUNGALS[row_label]
        label = f"{atm}"
        ry = margin + row * cell_size + cell_size // 2 + 5
        cv2.putText(heatmap, label, (5, ry), font, 0.4, (0, 0, 0), 1)
        
        for col in range(COLS):
            data = classified_wells.get((row, col))
            if data is None:
                continue
            
            score = data['growth_score']
            
            # Interpolate color: green (growth) -> yellow -> red (inhibition)
            r_val = int(255 * (1 - score))
            g_val = int(255 * score)
            b_val = 0
            color = (b_val, g_val, r_val)  # BGR
            
            x1 = margin + col * cell_size + 2
            y1 = margin + row * cell_size + 2
            x2 = x1 + cell_size - 4
            y2 = y1 + cell_size - 4
            
            cv2.rectangle(heatmap, (x1, y1), (x2, y2), color, -1)
            cv2.rectangle(heatmap, (x1, y1), (x2, y2), (100, 100, 100), 1)
            
            # Score text
            score_text = f"{score:.2f}"
            ts = cv2.getTextSize(score_text, font, 0.3, 1)[0]
            tx = x1 + (cell_size - 4 - ts[0]) // 2
            ty = y1 + (cell_size - 4 + ts[1]) // 2
            text_color = (255, 255, 255) if score < 0.5 else (0, 0, 0)
            cv2.putText(heatmap, score_text, (tx, ty), font, 0.3, text_color, 1)
    
    return heatmap


def save_csv_report(mic_results: list, classified_wells: dict, output_path: str):
    """Save detailed CSV report with MIC values and per-well scores."""
    with open(output_path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        
        # Header section
        writer.writerow(['MIC YST Plate Reader - Results Report'])
        writer.writerow([])
        
        # Summary table
        writer.writerow(['Row', 'Antifungal', 'Full Name', 'MIC (mg/L)', 
                         'MIC Column', 'Inhibition Threshold', 'Note'])
        for r in mic_results:
            mic_str = str(r['mic_value']) if r['mic_value'] is not None else 'N/A'
            writer.writerow([
                r['row'], r['antifungal'], r['antifungal_name'],
                r['note'] if r['note'] else mic_str,
                r['mic_column'] + 1 if r['mic_column'] is not None else 'N/A',
                f"{r['inhibition_threshold']*100:.0f}%",
                r['note']
            ])
        
        writer.writerow([])
        writer.writerow([])
        
        # Detailed per-well growth scores
        writer.writerow(['Growth Scores (0=inhibition, 1=growth)'])
        header = ['Row/ATM'] + [f'Col {i+1}' for i in range(COLS)]
        writer.writerow(header)
        
        for row_idx in range(ROWS):
            row_label = ROW_LABELS[row_idx]
            atm = ANTIFUNGALS[row_label]
            row_data = [f'{row_label}-{atm}']
            for col_idx in range(COLS):
                data = classified_wells.get((row_idx, col_idx))
                if data:
                    row_data.append(f"{data['growth_score']:.3f}")
                else:
                    row_data.append('N/A')
            writer.writerow(row_data)
        
        writer.writerow([])
        
        # Concentration reference
        writer.writerow(['Concentration Reference (mg/L)'])
        header = ['Row/ATM'] + [f'Col {i+1}' for i in range(COLS)]
        writer.writerow(header)
        for row_idx in range(ROWS):
            row_label = ROW_LABELS[row_idx]
            atm = ANTIFUNGALS[row_label]
            concs = CONCENTRATIONS[row_label]
            row_data = [f'{row_label}-{atm}']
            for c in concs:
                row_data.append(str(c) if c is not None else 'K')
            writer.writerow(row_data)
    
    print(f"[INFO] CSV report saved to: {output_path}")
