"""
MIC YST Plate Reader - Main Entry Point
Reads a 96-well microplate image and determines MIC values for antifungal agents.

Usage:
    python main.py <image_path> [--output-dir <dir>]
"""

import sys
import os
import cv2
import numpy as np

# Add current dir to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from plate_detector import detect_plate
from well_extractor import extract_wells
from color_classifier import classify_wells
from mic_calculator import calculate_mic, print_results
from visualizer import (
    create_annotated_image, create_score_heatmap,
    save_csv_report
)


def run_pipeline(image_path: str, output_dir: str = '.'):
    """Execute the full MIC plate reading pipeline."""
    
    print("=" * 60)
    print("  MIC YST Plate Reader v1.0")
    print("  EUCAST Uyumlu Mikrodilüsyon MIC Tayini")
    print("=" * 60)
    print()
    
    # --- Step 1: Load image ---
    print("[1/6] Görüntü yükleniyor...")
    image = cv2.imread(image_path)
    if image is None:
        print(f"[ERROR] Görüntü okunamadı: {image_path}")
        sys.exit(1)
    print(f"       Boyut: {image.shape[1]}x{image.shape[0]} px")
    
    # --- Step 2: Detect plate ---
    print("[2/6] Plak bölgesi tespit ediliyor...")
    plate = detect_plate(image)
    print(f"       Plak boyutu: {plate.shape[1]}x{plate.shape[0]} px")
    
    # --- Step 3: Extract wells ---
    print("[3/6] Kuyucuklar çıkarılıyor (8×12 grid)...")
    wells = extract_wells(plate)
    print(f"       {len(wells)} kuyucuk çıkarıldı")
    
    # Debug: print sample well HSV values
    from config import ROW_LABELS, ANTIFUNGALS
    print("\n       Örnek HSV değerleri (medyan):")
    for row_idx in [0, 7]:  # Row A and Row H
        for col_idx in [0, 5, 11]:
            w = wells.get((row_idx, col_idx))
            if w:
                h, s, v = w['hsv_median']
                r, g, b = w['rgb_mean']
                label = f"{ROW_LABELS[row_idx]}{col_idx+1}"
                print(f"       {label}: H={h:.1f} S={s:.1f} V={v:.1f} | R={r:.0f} G={g:.0f} B={b:.0f}")
    print()
    
    # --- Step 4: Classify wells ---
    print("[4/6] Renk sınıflandırması yapılıyor (hibrit: relatif + absolut)...")
    classified = classify_wells(wells)
    
    # Count classifications
    counts = {'growth': 0, 'inhibition': 0, 'partial': 0}
    for data in classified.values():
        counts[data['classification']] += 1
    print(f"       Üreme: {counts['growth']}, İnhibisyon: {counts['inhibition']}, Kısmi: {counts['partial']}")
    print()
    
    # --- Step 5: Calculate MIC ---
    print("[5/6] MIC değerleri hesaplanıyor...")
    results = calculate_mic(classified)
    print_results(results)
    
    # --- Step 6: Generate outputs ---
    print("[6/6] Çıktılar oluşturuluyor...")
    
    os.makedirs(output_dir, exist_ok=True)
    base_name = os.path.splitext(os.path.basename(image_path))[0]
    
    # Annotated image
    annotated = create_annotated_image(plate, classified, results)
    annotated_path = os.path.join(output_dir, f"{base_name}_annotated.png")
    cv2.imwrite(annotated_path, annotated)
    print(f"       Annotated görsel: {annotated_path}")
    
    # Heatmap
    heatmap = create_score_heatmap(classified)
    heatmap_path = os.path.join(output_dir, f"{base_name}_heatmap.png")
    cv2.imwrite(heatmap_path, heatmap)
    print(f"       Isı haritası: {heatmap_path}")
    
    # CSV report
    csv_path = os.path.join(output_dir, f"{base_name}_report.csv")
    save_csv_report(results, classified, csv_path)
    
    print()
    print("✓ İşlem tamamlandı!")
    print()
    
    return results, annotated_path, heatmap_path, csv_path


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Kullanım: python main.py <görüntü_yolu> [--output-dir <klasör>]")
        sys.exit(1)
    
    image_path = sys.argv[1]
    output_dir = '.'
    
    if '--output-dir' in sys.argv:
        idx = sys.argv.index('--output-dir')
        if idx + 1 < len(sys.argv):
            output_dir = sys.argv[idx + 1]
    
    run_pipeline(image_path, output_dir)
