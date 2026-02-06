"""
MIC Calculator - Determines MIC values from classified well data.
Follows EUCAST reading rules:
  - AMB: 90% inhibition (nearly complete color change)
  - Others: ≥50% inhibition
"""

import numpy as np
from config import (
    ROWS, COLS, ROW_LABELS, ANTIFUNGALS, CONCENTRATIONS,
    INHIBITION_THRESHOLDS, CONTROL_WELL, ANTIFUNGAL_FULL_NAMES
)


def calculate_mic(classified_wells: dict) -> list:
    """
    Calculate MIC values for each antifungal row.
    
    MIC = concentration of the first well that shows sufficient inhibition
    compared to the control well.
    
    Returns list of dicts:
    [
        {
            'row': 'A',
            'antifungal': 'AND',
            'antifungal_name': 'Anidulafungin',
            'mic_value': 0.125,  # mg/L or None
            'mic_column': 5,     # 0-indexed or None
            'inhibition_threshold': 0.50,
            'well_scores': [...],
            'note': ''
        },
        ...
    ]
    """
    # Get control well growth score as baseline
    ctrl_row_idx = ROW_LABELS.index(CONTROL_WELL[0]) if isinstance(CONTROL_WELL[0], str) else CONTROL_WELL[0]
    ctrl_data = classified_wells.get((ctrl_row_idx, CONTROL_WELL[1]))
    
    if ctrl_data is None:
        raise ValueError("Control well not found!")
    
    ctrl_growth_score = ctrl_data['growth_score']
    print(f"[INFO] Control (K) growth score: {ctrl_growth_score:.3f}")
    
    # Validate control: it should show growth (high score)
    if ctrl_growth_score < 0.4:
        print("[WARN] Control well shows low growth score! Results may be unreliable.")
        print("       Per protocol: if K doesn't show growth (pink), test should be repeated.")
    
    # Check for column 12 edge artifact
    # If all col 12 wells have unusually low saturation, flag as edge artifact
    col12_sats = []
    col11_sats = []
    for row_idx in range(ROWS):
        d12 = classified_wells.get((row_idx, 11))
        d11 = classified_wells.get((row_idx, 10))
        if d12:
            col12_sats.append(d12['hsv_median'][1])
        if d11:
            col11_sats.append(d11['hsv_median'][1])
    
    col12_edge_artifact = False
    if col12_sats and col11_sats:
        med_12 = np.median(col12_sats)
        med_11 = np.median(col11_sats)
        # If col 12 has much lower saturation than col 11, likely edge artifact
        if med_12 < 25 and med_11 > med_12 * 1.5:
            col12_edge_artifact = True
            print("[WARN] Column 12 olası kenar artefaktı tespit edildi (düşük doygunluk).")
            print(f"       Col 11 median S: {med_11:.0f}, Col 12 median S: {med_12:.0f}")
    
    results = []
    
    for row_idx in range(ROWS):
        row_label = ROW_LABELS[row_idx]
        antifungal = ANTIFUNGALS[row_label]
        full_name = ANTIFUNGAL_FULL_NAMES.get(antifungal, antifungal)
        concentrations = CONCENTRATIONS[row_label]
        threshold = INHIBITION_THRESHOLDS[antifungal]
        
        # Collect growth scores for this row
        well_scores = []
        for col_idx in range(COLS):
            data = classified_wells.get((row_idx, col_idx))
            if data:
                well_scores.append(data['growth_score'])
            else:
                well_scores.append(None)
        
        # Determine starting column for MIC search
        if row_label == 'H':
            # Row H: column 0 is K (control), MIC search starts at column 1
            start_col = 1
        else:
            start_col = 0
        
        # Find MIC: first well where inhibition >= threshold
        # inhibition = 1.0 - (well_growth_score / ctrl_growth_score)
        mic_value = None
        mic_column = None
        note = ''
        
        for col_idx in range(start_col, COLS):
            score = well_scores[col_idx]
            if score is None:
                continue
            
            # Calculate relative inhibition
            if ctrl_growth_score > 0.01:
                inhibition = 1.0 - (score / ctrl_growth_score)
            else:
                inhibition = 0.0
            
            inhibition = max(0.0, inhibition)
            
            if inhibition >= threshold:
                mic_value = concentrations[col_idx]
                mic_column = col_idx
                break
        
        # Handle edge cases
        if mic_value is None and all(s is not None and s > 0.5 for s in well_scores[start_col:]):
            note = f'>{concentrations[-1]}'
            mic_value = f'>{concentrations[-1]}'
            if col12_edge_artifact:
                note += ' (kolon 12 kenar artefaktı olabilir)'
        elif mic_value is None:
            note = 'Belirlenemedi'
        
        # Check if MIC is at the lowest concentration (might be below range)
        if mic_column == start_col and mic_value is not None and not isinstance(mic_value, str):
            note = f'≤{mic_value}'
        
        results.append({
            'row': row_label,
            'antifungal': antifungal,
            'antifungal_name': full_name,
            'mic_value': mic_value,
            'mic_column': mic_column,
            'inhibition_threshold': threshold,
            'well_scores': well_scores,
            'note': note,
        })
    
    return results


def print_results(results: list):
    """Print MIC results to terminal in a formatted table."""
    print("\n" + "=" * 70)
    print("MIC SONUÇLARI / MIC RESULTS")
    print("=" * 70)
    print(f"{'Satır':<6} {'Antifungal':<18} {'MIC (mg/L)':<14} {'Not'}")
    print("-" * 70)
    
    for r in results:
        mic_str = str(r['mic_value']) if r['mic_value'] is not None else 'N/A'
        note = r['note']
        threshold_note = f"(%{int(r['inhibition_threshold']*100)} inh.)" if r['antifungal'] == 'AMB' else ''
        
        print(f"{r['row']:<6} {r['antifungal_name']:<18} {mic_str:<14} {note} {threshold_note}")
    
    print("=" * 70)
    print("K = Pozitif kontrol kuyucuğu (H1)")
    print("AMB için %90, diğer antifungaller için ≥%50 inhibisyon kriteri uygulanmıştır.")
    print()
