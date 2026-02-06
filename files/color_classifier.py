"""
Color Classifier v3 - Classifies each well as growth (pink) or inhibition (blue/purple).
Uses hybrid approach: relative scoring (vs control) + absolute HSV thresholds.
NEW: Gradient-based neighbor analysis for uncertain wells (0.30-0.50 zone).

Key insight from actual plate data:
  - Growth (pink): Hue ~165-180/0-10, LOW saturation (15-40), R-B > +10
  - Inhibition (purple/magenta): Hue ~145-165, HIGH saturation (60-200+), R-B < +8
  - Saturation is the PRIMARY discriminator, hue shift is secondary

Classification thresholds (v3):
  - score > 0.50 → PINK (growth) - HIGH confidence
  - score < 0.30 → PURPLE (inhibition) - HIGH confidence
  - 0.30-0.50 → Use neighbor analysis - MEDIUM/LOW confidence
"""

import numpy as np
from config import (
    ROWS, COLS, ROW_LABELS, ANTIFUNGALS, CONTROL_WELL,
    RELATIVE_WEIGHT, ABSOLUTE_WEIGHT, INHIBITION_THRESHOLDS
)


# Classification thresholds
PINK_THRESHOLD = 0.50
PURPLE_THRESHOLD = 0.30
FALLBACK_THRESHOLD = 0.40  # For unresolved uncertain wells


class Confidence:
    """Confidence levels for well classification."""
    HIGH = 'high'      # Direct threshold (>0.50 or <0.30)
    MEDIUM = 'medium'  # Resolved via neighbor analysis
    LOW = 'low'        # Fallback classification, needs manual review


def classify_wells(wells: dict) -> dict:
    """
    Classify each well as growth or inhibition.
    Uses two-phase approach:
      1. Initial classification with thresholds
      2. Neighbor analysis for uncertain wells
    """
    ctrl_row, ctrl_col = CONTROL_WELL
    ctrl_row_idx = ROW_LABELS.index(ctrl_row) if isinstance(ctrl_row, str) else ctrl_row
    control_data = wells.get((ctrl_row_idx, ctrl_col))

    if control_data is None:
        raise ValueError("Control well (K) not found!")

    ctrl_hsv = control_data['hsv_median']
    ctrl_rgb = control_data['rgb_mean']

    print(f"[INFO] Control well (K) HSV median: H={ctrl_hsv[0]:.1f}, S={ctrl_hsv[1]:.1f}, V={ctrl_hsv[2]:.1f}")
    print(f"[INFO] Control well (K) RGB mean: R={ctrl_rgb[0]:.1f}, G={ctrl_rgb[1]:.1f}, B={ctrl_rgb[2]:.1f}")

    # Step 1: Pre-classify obvious wells for calibration
    growth_profiles = []
    inhibition_profiles = []

    for (r, c), data in wells.items():
        h, s, v = data['hsv_median']
        rgb = data['rgb_mean']
        rb_diff = rgb[0] - rgb[2]

        if s < 35 and rb_diff > 10:
            growth_profiles.append(data)
        elif s > 80 and 140 <= h <= 165:
            inhibition_profiles.append(data)

    growth_sat_median = np.median([d['hsv_median'][1] for d in growth_profiles]) if growth_profiles else ctrl_hsv[1]
    inhib_sat_median = np.median([d['hsv_median'][1] for d in inhibition_profiles]) if inhibition_profiles else 140.0
    sat_midpoint = (growth_sat_median + inhib_sat_median) / 2

    print(f"[INFO] Growth saturation median: {growth_sat_median:.1f}")
    print(f"[INFO] Inhibition saturation median: {inhib_sat_median:.1f}")
    print(f"[INFO] Saturation midpoint: {sat_midpoint:.1f}")
    print(f"[INFO] Calibration: {len(growth_profiles)} growth, {len(inhibition_profiles)} inhibition wells")

    # Step 2: Calculate scores and initial classification
    classified = {}
    uncertain_count = 0

    for (row, col), data in wells.items():
        well_hsv = data['hsv_median']
        well_rgb = data['rgb_mean']

        rel_score = compute_relative_score(
            well_hsv, well_rgb, ctrl_hsv, ctrl_rgb,
            growth_sat_median, inhib_sat_median
        )

        abs_score = compute_absolute_score(
            well_hsv, well_rgb,
            growth_sat_median, inhib_sat_median, sat_midpoint
        )

        growth_score = (RELATIVE_WEIGHT * rel_score) + (ABSOLUTE_WEIGHT * abs_score)
        growth_score = np.clip(growth_score, 0.0, 1.0)

        # Phase 1: Initial classification with new thresholds
        if growth_score > PINK_THRESHOLD:
            classification = 'growth'
            confidence = Confidence.HIGH
        elif growth_score < PURPLE_THRESHOLD:
            classification = 'inhibition'
            confidence = Confidence.HIGH
        else:
            classification = 'uncertain'
            confidence = Confidence.LOW
            uncertain_count += 1

        classified[(row, col)] = {
            **data,
            'growth_score': growth_score,
            'relative_score': rel_score,
            'absolute_score': abs_score,
            'classification': classification,
            'confidence': confidence,
        }

    print(f"[INFO] Phase 1: {uncertain_count} uncertain wells (score 0.30-0.50)")

    # Step 3: Resolve uncertain wells using neighbor analysis
    classified = resolve_uncertain_wells(classified)

    # Count final classifications
    final_counts = {'growth': 0, 'inhibition': 0, 'partial': 0}
    low_confidence = 0
    for data in classified.values():
        final_counts[data['classification']] += 1
        if data['confidence'] == Confidence.LOW:
            low_confidence += 1

    print(f"[INFO] Phase 2: Resolved to {final_counts['growth']} growth, {final_counts['inhibition']} inhibition, {final_counts['partial']} partial")
    if low_confidence > 0:
        print(f"[WARN] {low_confidence} wells have LOW confidence - manual review recommended")

    return classified


def resolve_uncertain_wells(classified: dict) -> dict:
    """
    Use gradient-based neighbor analysis to resolve uncertain wells.

    MIC plates have predictable gradient: left (low conc) = pink → right (high conc) = purple
    Uncertain wells are typically at the transition point (MIC).
    """
    resolved_count = 0

    for row in range(ROWS):
        for col in range(COLS):
            well = classified.get((row, col))
            if well is None or well['classification'] != 'uncertain':
                continue

            # Get neighbors
            left = classified.get((row, col - 1)) if col > 0 else None
            right = classified.get((row, col + 1)) if col < COLS - 1 else None

            left_class = left['classification'] if left else None
            right_class = right['classification'] if right else None

            # Apply decision rules
            new_class, confidence = apply_neighbor_rules(
                well['growth_score'], left_class, right_class
            )

            classified[(row, col)]['classification'] = new_class
            classified[(row, col)]['confidence'] = confidence

            if confidence != Confidence.LOW:
                resolved_count += 1

    print(f"[INFO] Neighbor analysis resolved {resolved_count} uncertain wells")

    return classified


def apply_neighbor_rules(score: float, left_class: str, right_class: str) -> tuple:
    """
    Determine classification based on neighboring wells.

    Returns:
        (classification, confidence)
    """
    # Rule 1: Transition point - left is pink, right is purple
    # This is the MIC point - classify as inhibition
    if left_class == 'growth' and right_class == 'inhibition':
        return 'inhibition', Confidence.MEDIUM

    # Rule 2: Left is pink, right is uncertain or edge
    # Likely still in growth zone
    if left_class == 'growth' and right_class in ('uncertain', None):
        return 'growth', Confidence.MEDIUM

    # Rule 3: Left is uncertain or edge, right is purple
    # Likely in inhibition zone
    if left_class in ('uncertain', None) and right_class == 'inhibition':
        return 'inhibition', Confidence.MEDIUM

    # Rule 4: Both neighbors are the same color
    if left_class == 'growth' and right_class == 'growth':
        return 'growth', Confidence.MEDIUM
    if left_class == 'inhibition' and right_class == 'inhibition':
        return 'inhibition', Confidence.MEDIUM

    # Rule 5: Edge cases (first or last column)
    if left_class is None and right_class == 'inhibition':
        return 'inhibition', Confidence.MEDIUM
    if left_class == 'growth' and right_class is None:
        return 'growth', Confidence.MEDIUM

    # Rule 6: Fallback - use midpoint threshold
    # This should rarely happen if neighbors are classified
    if score >= FALLBACK_THRESHOLD:
        return 'growth', Confidence.LOW
    else:
        return 'inhibition', Confidence.LOW


def compute_relative_score(well_hsv, well_rgb, ctrl_hsv, ctrl_rgb,
                           growth_sat, inhib_sat) -> float:
    """
    Score how similar a well is to the control (growth) well.
    1.0 = growth, 0.0 = inhibition.
    """
    w_h, w_s, w_v = well_hsv
    c_h, c_s, c_v = ctrl_hsv

    # Feature 1: Saturation distance (PRIMARY)
    sat_range = max(inhib_sat - growth_sat, 30)
    sat_normalized = (w_s - growth_sat) / sat_range
    sat_score = 1.0 - np.clip(sat_normalized, 0.0, 1.0)

    # Feature 2: Hue distance
    hue_dist = circular_hue_distance(w_h, c_h)
    hue_score = max(0.0, 1.0 - (hue_dist / 35.0))

    # Feature 3: R-B difference
    w_rb = well_rgb[0] - well_rgb[2]
    c_rb = ctrl_rgb[0] - ctrl_rgb[2]

    if abs(c_rb) > 3:
        rb_ratio = w_rb / c_rb
        rb_score = np.clip(rb_ratio, -0.2, 1.2)
        rb_score = max(0.0, min(1.0, rb_score))
    else:
        rb_score = 1.0 if w_rb > 0 else 0.0

    # Feature 4: Green channel depression
    w_g_ratio = well_rgb[1] / (sum(well_rgb) / 3 + 1)
    c_g_ratio = ctrl_rgb[1] / (sum(ctrl_rgb) / 3 + 1)
    g_diff = w_g_ratio - c_g_ratio
    g_score = np.clip(1.0 + g_diff * 5, 0.0, 1.0)

    # Weighted - saturation dominant
    score = (0.40 * sat_score +
             0.20 * hue_score +
             0.20 * rb_score +
             0.20 * g_score)

    return float(np.clip(score, 0.0, 1.0))


def compute_absolute_score(well_hsv, well_rgb, growth_sat, inhib_sat, sat_mid) -> float:
    """
    Absolute scoring based on known color characteristics.
    """
    h, s, v = well_hsv
    r, g, b = well_rgb
    rb_diff = r - b

    score = 0.5

    # --- Saturation-based scoring (strongest signal) ---
    if s < 35:
        score += 0.35
    elif s > 80:
        score -= 0.40
    elif s > 50:
        score -= 0.20
    else:
        t = (s - 35) / 15.0
        score -= t * 0.15

    # --- Hue-based adjustment ---
    if 145 <= h <= 165:
        score -= 0.15
        if s > 60:
            score -= 0.10
    elif (h >= 165 or h <= 12):
        score += 0.10

    # --- R-B adjustment ---
    if rb_diff < 0:
        score -= 0.10
    elif rb_diff > 15:
        score += 0.10

    # --- Green depression check ---
    if g < r * 0.7 and g < b * 0.8 and s > 50:
        score -= 0.15

    return float(np.clip(score, 0.0, 1.0))


def circular_hue_distance(h1: float, h2: float) -> float:
    """Compute shortest angular distance between two hues (0-179 scale)."""
    diff = abs(h1 - h2)
    return min(diff, 180 - diff)
